#pragma once

#include <memory>
#include <vector>
#include <type_traits>

/**
 * @brief Class to give a Fletcher type to objects.
 * @tparam T The class describing the type of the typed object.
 */
template<class T>
class TypedBy {
 public:
  explicit TypedBy(T type) : type_(type) {}

  virtual ~TypedBy() = default;

  virtual T type() { return type_; }

 private:
  T type_;
};

/**
 * @brief A class to allow Fletcher objects to be derived from some other Fletcher object.
 * @tparam T The type of the object it was derived from.
 */
template<class T>
class DerivedFrom {
 public:
  explicit DerivedFrom(T *source) : source_(source) {}

  void setSource(T *source) { source_ = source; }

  T *source() { return source_; }

 private:
  T *source_;
};

/**
 * @brief A class to allow Fletcher objects to be derived from some other Fletcher object.
 * @tparam T The type of the object it was derived from.
 */
template<class T>
class Destination {
 public:
  explicit Destination(T *dest) : dest_(dest) {}

  T *dest() { return dest_; }

 private:
  T *dest_;
};

/**
 * @brief A class to allow Fletcher objects to be children of some parent Fletcher object.
 * @tparam T The type of the parent object.
 */
template<class T>
class ChildOf {
 public:
  explicit ChildOf(T *parent) : parent_(parent) {}

  bool hasParent() { return parent_ != nullptr; }

  T *parent() { return parent_; }

  void setParent(T *parent) { parent_ = parent; }

 private:
  T *parent_;
};

/**
 * @brief A class to allow Fletcher objects to be parent of one or several children.
 * @tparam T The type of the child object.
 */
template<class T>
class ParentOf {
 public:
  ParentOf() = default;

  explicit ParentOf(std::shared_ptr<T> child) { addChild(child); }

  T child(int i) { return children_[i]; }

  std::vector<std::shared_ptr<T>> children() { return children_; }

  int num_children() { return (int) children_.size(); };

  void addChildren(std::vector<std::shared_ptr<T>> children) {
    children_.insert(children_.end(),
                     children.begin(),
                     children.end());
  }

  void addChild(std::shared_ptr<T> child) { children_.push_back(child); }

 private:
  std::vector<std::shared_ptr<T>> children_;
};

template<class T>
std::vector<std::shared_ptr<T>> flatten(std::shared_ptr<T> root) {
  static_assert(std::is_base_of<ParentOf<T>, T>::value, "T must extend ParentOf<T>.");
  std::vector<std::shared_ptr<T>> ret;
  ret.push_back(root);
  auto root_as_parentof = std::dynamic_pointer_cast<ParentOf<T>>(root);
  if (root_as_parentof != nullptr) {
    for (const auto &c: root_as_parentof->children()) {
      auto child = flatten<T>(c);
      ret.insert(ret.end(), child.begin(), child.end());
    }
  } else {
    throw std::runtime_error("Root class does not extend ParentOf<T>.");
  }
  return ret;
}

template<class T>
std::vector<T *> flatten(T *root) {
  static_assert(std::is_base_of<ParentOf<T>, T>::value, "T must extend ParentOf<T>.");
  std::vector<T *> ret;
  ret.push_back(root);
  auto root_as_parentof = dynamic_cast<ParentOf<T> *>(root);
  if (root_as_parentof != nullptr) {
    for (const auto &c: root_as_parentof->children()) {
      auto child = flatten<T>(c.get());
      ret.insert(ret.end(), child.begin(), child.end());
    }
  } else {
    throw std::runtime_error("Root class does not extend ParentOf<T>.");
  }
  return ret;
}

template<class T>
T *rootOf(T *obj) {
  static_assert(std::is_base_of<ChildOf<T>, T>::value, "T must extend ChildOf<T>.");
  auto obj_as_childof = dynamic_cast<ChildOf<T> *>(obj);
  if (obj_as_childof != nullptr) {
    if (obj_as_childof->hasParent()) {
      return rootOf(obj_as_childof->parent());
    }
  } else {
    throw std::runtime_error("Object class does not extend ChildOf<T>.");
  }
  return obj;
}

template<class T1, class T2>
T1 *castOrThrow(T2 *ptr) {
  auto ret = dynamic_cast<T1 *>(ptr);
  if (ret != nullptr) {
    return ret;
  } else {
    throw std::runtime_error("Could not cast pointer to T.");
  }
}

template<class T1, class T2>
std::shared_ptr<T1> castOrThrow(std::shared_ptr<T2> ptr) {
  auto ret = std::dynamic_pointer_cast<T1>(ptr);
  if (ret != nullptr) {
    return ret;
  } else {
    throw std::runtime_error(std::string("Could not cast pointer to ") + typeid(T1).name());
  }
}
