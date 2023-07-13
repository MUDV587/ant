#pragma once

#include <core/Layout.h>
#include <memory>
#include <vector>

namespace Rml {
	class Element;

	class Node {
	public:
		enum class Type : uint8_t {
			Element = 0,
			Text,
		};
		Node(Type type);
		virtual ~Node();
		Type GetType() const;

		virtual void CalculateLayout() = 0;
		virtual bool UpdateLayout() = 0;
		virtual const Rect& GetContentRect() const = 0;

		Element* GetParentNode() const;
		void ResetParentNode();
		virtual void SetParentNode(Element* parent);
	
		virtual Node* Clone(bool deep = true) const = 0;
		virtual void Render() = 0;
		virtual float GetZIndex() const = 0;
		virtual Element* ElementFromPoint(Point point) = 0;
		virtual std::string GetInnerHTML() const = 0;
		virtual std::string GetOuterHTML() const = 0;
		virtual void SetInnerHTML(const std::string& html) = 0;
		virtual void SetOuterHTML(const std::string& html) = 0;

	private:
		Element* parent = nullptr;
		Type type;
	};

	class LayoutNode: public Node {
	public:
		LayoutNode(Layout::UseElement);
		LayoutNode(Layout::UseText, void* context);

		bool UpdateLayout() override;

		Layout& GetLayout();
		const Layout& GetLayout() const;
		bool IsVisible() const;
		void SetVisible(bool visible);
		const Rect& GetBounds() const;

		void InsertChild(const LayoutNode* child, uint32_t index);
		void RemoveChild(const LayoutNode* child);

	private:
		Layout layout;
		Rect bounds;
		bool visible = true;
	};
}